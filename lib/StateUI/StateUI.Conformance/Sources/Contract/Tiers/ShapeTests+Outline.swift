// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// How a shape's outline is drawn, read off what the host draws: its dashes and where they start, its ends, and the
/// joins of its corners - each case made for every shape, a corner's on a shape that has one.
/// Design: docs/design/host/conformance.md#a-drawing-read-by-its-colours
extension ShapeTests {
    /// The outline cases.
    @MainActor
    static func outlineCases(_ element: String) -> [ConformanceCase] {
        [dashed(element), dashShifted(element), capped(element), joined(element), limited(element)]
    }

    /// A dashed outline leaves gaps along its run, which a solid one does not.
    @MainActor
    static func dashed(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).isDashedAsTheTreeSays", proves: [
            Covered(ShapeContract.dash, on: element),
        ]) { s in
            s.start {
                VStack {
                    Specimens.view(element, outlined(element, width: 4) + [Write(ShapeContract.dash, [1.0, 1.0])])
                }
            }
            let shape = try s.specimen(element)
            let run = try Self.run(along: element, width: 4, on: shape, in: s)
            s.expect(run.contains(true) && run.contains(false), true, "dashes and gaps along its outline")
        }
    }

    /// The dashes start as far along the pattern as their phase says: shifted by one dash, they stand where the gaps
    /// stood.
    @MainActor
    static func dashShifted(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).startsItsDashesWhereThePhaseSays", proves: [
            Covered(ShapeContract.dashPhase, on: element),
        ], needs: [Covered(ShapeContract.dash, on: element), Covered(ButtonContract.clicked)]) { s in
            let shifted = State(wrappedValue: false)
            s.start {
                Specimens.page(element, outlined(element, width: 4) + [
                    Write(ShapeContract.dash, [2.0, 2.0]),
                    Write(ShapeContract.dashPhase, shifted.wrappedValue ? 2.0 : 0),
                ], beside: [Button("Shift").onClicked { shifted.wrappedValue = true }.id("change")])
            }
            let shape = try s.specimen(element)
            let first = try Self.run(along: element, width: 4, on: shape, in: s)

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try Self.run(along: element, width: 4, on: shape, in: s) != first }
            s.expect(try Self.run(along: element, width: 4, on: shape, in: s) != first, true, "the dashes moved along")
        }
    }

    /// Short dashes - dashes and gaps are measured in the outline's widths - take more of the outline with squared
    /// ends than with flat ones: each end reaches half the line's width past where the dash stops.
    @MainActor
    static func capped(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).endsItsLinesAsTheTreeSays", proves: [
            Covered(ShapeContract.lineCap, on: element),
        ], needs: [Covered(ShapeContract.dash, on: element), Covered(ButtonContract.clicked)]) { s in
            let squared = State(wrappedValue: false)
            s.start {
                Specimens.page(element, outlined(element, width: 4) + [
                    Write(ShapeContract.dash, [0.5, 3.5]),
                    Write(ShapeContract.lineCap, squared.wrappedValue ? LineCap.square : .flat),
                ], beside: [Button("Square").onClicked { squared.wrappedValue = true }.id("change")])
            }
            let shape = try s.specimen(element)
            let flat = try Self.run(along: element, width: 4, on: shape, in: s).filter { $0 }.count

            try s.perform(.activate, on: s.element("change"))
            let square = { try Self.run(along: element, width: 4, on: shape, in: s).filter { $0 }.count }
            try s.settle { try square() >= flat + 3 }
            s.expect(try square() >= flat + 3, true, "squared ends reach past each dash")
        }
    }

    /// A corner is mitred to a point, and cut across once the tree bevels it.
    @MainActor
    static func joined(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).joinsItsCornersAsTheTreeSays", proves: [
            Covered(ShapeContract.lineJoin, on: element),
        ], needs: [Covered(ButtonContract.clicked)]) { s in
            let bevelled = State(wrappedValue: false)
            s.start {
                Specimens.page(element, outlined(element, width: 8) + [
                    Write(ShapeContract.lineJoin, bevelled.wrappedValue ? LineJoin.bevel : .miter),
                    Write(ShapeContract.miterLimit, 10.0),
                ], beside: [Button("Bevel").onClicked { bevelled.wrappedValue = true }.id("change")])
            }
            guard let tip = Self.cornerTip(element) else { throw s.absent(Self.cornerless(element)) }
            let shape = try s.specimen(element)
            try s.settle { try s.shows(.red, on: shape, at: tip) }
            s.expect(try s.color(of: shape, at: tip), shows: .red, "a mitred corner reaches its point")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.color(of: shape, at: tip) == nil }
            s.expect(try s.color(of: shape, at: tip), nil, "a bevelled one is cut across")
        }
    }

    /// A mitred corner is cut across where its point would reach past the limit the tree sets.
    @MainActor
    static func limited(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).limitsItsMitresAsTheTreeSays", proves: [
            Covered(ShapeContract.miterLimit, on: element),
        ], needs: [Covered(ShapeContract.lineJoin, on: element), Covered(ButtonContract.clicked)]) { s in
            let limited = State(wrappedValue: false)
            s.start {
                Specimens.page(element, outlined(element, width: 8) + [
                    Write(ShapeContract.lineJoin, LineJoin.miter),
                    Write(ShapeContract.miterLimit, limited.wrappedValue ? 1.0 : 10.0),
                ], beside: [Button("Limit").onClicked { limited.wrappedValue = true }.id("change")])
            }
            guard let tip = Self.cornerTip(element) else { throw s.absent(Self.cornerless(element)) }
            let shape = try s.specimen(element)
            try s.settle { try s.shows(.red, on: shape, at: tip) }
            s.expect(try s.color(of: shape, at: tip), shows: .red, "a right angle's mitre within ten")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.color(of: shape, at: tip) == nil }
            s.expect(try s.color(of: shape, at: tip), nil, "cut across past a limit of one")
        }
    }

    /// `element` outlined in red, `width` wide, filled with nothing, 40 by 40, a figure with a corner set in from its
    /// room where it has points of its own.
    @MainActor
    static func outlined(_ element: String, width: Double) -> [any Worn] {
        inset(element) + [
            Write(ShapeContract.stroke, Brush.solidColor(.red)), Write(ShapeContract.lineWidth, width),
            Write(VisualElementContract.width, 40), Write(VisualElementContract.height, 40),
        ]
    }

    /// A figure of points set eight in from the room, so its corners' outer side stands inside it.
    @MainActor
    static func inset(_ element: String) -> [any Worn] {
        let square = [Point(8, 8), Point(32, 8), Point(32, 32), Point(8, 32)]
        let atItsSize = Write(ShapeContract.contentMode, ContentMode.center)
        return switch element {
        case "Line": [
            Write(LineContract.x1, 0), Write(LineContract.y1, 20),
            Write(LineContract.x2, 40), Write(LineContract.y2, 20),
        ]
        case "Polygon": [Write(PolygonContract.points, square), atItsSize]
        case "Polyline": [Write(PolylineContract.points, square + [Point(8, 8)]), atItsSize]
        case "Path": [Write(PathContract.data, "M 8 8 L 32 8 L 32 32 L 8 32 Z"), atItsSize]
        default: []
        }
    }

    /// Whether the outline is drawn at each of a run of points along it, `width` wide: a line's middle, a
    /// rectangle's top edge, an ellipse's top, a figure's top side.
    @MainActor
    static func run(along element: String, width: Double, on shape: MountedElement, in s: Session) throws -> [Bool] {
        try points(along: element, width: width).map { try s.shows(.red, on: shape, at: $0) }
    }

    /// The points along `element`'s outline the run is read at.
    static func points(along element: String, width: Double) -> [Point] {
        switch element {
        case "Line": return (2...38).map { Point(Double($0), 20) }
        case "Rectangle": return (Int(width) + 2...38 - Int(width)).map { Point(Double($0), width / 2) }
        case "Ellipse":
            let radius = 20 - width / 2
            return (8...32).map { x in
                let across = Double(x) - 20
                return Point(Double(x), 20 - (radius * radius - across * across).squareRoot())
            }
        default: return (10...30).map { Point(Double($0), 8) }
        }
    }

    /// A point just inside the outer side of a corner, eight wide, that a mitre covers and a bevel leaves bare; nil
    /// for a shape with no corner.
    static func cornerTip(_ element: String) -> Point? {
        switch element {
        case "Line", "Ellipse": nil
        case "Rectangle": Point(0, 0)
        default: Point(35, 5)
        }
    }

    /// Why a shape's corners prove nothing: it has none.
    static func cornerless(_ element: String) -> String {
        "\(element == "Line" ? "a line" : "an ellipse") has no corner its outline joins at"
    }
}
