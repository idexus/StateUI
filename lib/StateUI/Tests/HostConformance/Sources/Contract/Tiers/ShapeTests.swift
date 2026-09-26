// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// `ShapeContract` on a host: a shape is filled and outlined as the tree says, the colours the tree changes them to
/// drawn, and every way its outline is drawn - its width, dashes, ends, joins - its placement in its room and its
/// transform held as the tree gives them; each case made for every shape.
@_spi(Host) public enum ShapeTests: ConformanceFamily {
    public static let name = "Shape"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(ShapeContract.self).flatMap { element in
            [
                filled(element), outlined(element), placedByItsAspect(element), movedByItsTransform(element),
                Aspects.holds(ShapeContract.fill, on: element, .solidColor(.red), then: .solidColor(.blue), with: figure(element)),
                Aspects.holds(ShapeContract.stroke, on: element, .solidColor(.red), then: .solidColor(.blue), with: figure(element)),
                Aspects.holds(ShapeContract.strokeWidth, on: element, 2, then: 6, with: figure(element)),
                Aspects.holds(ShapeContract.strokeDashPattern, on: element, [3, 2], then: [1, 1], with: figure(element)),
                Aspects.holds(ShapeContract.strokeDashOffset, on: element, 0, then: 2.5, with: figure(element)),
                Aspects.holds(ShapeContract.strokeLineCap, on: element, .flat, then: .round, with: figure(element)),
                Aspects.holds(ShapeContract.strokeLineJoin, on: element, .miter, then: .bevel, with: figure(element)),
                Aspects.holds(ShapeContract.strokeMiterLimit, on: element, 10, then: 4, with: figure(element)),
                Aspects.holds(ShapeContract.aspect, on: element, .fit, then: .stretch, with: figure(element)),
                Aspects.holds(ShapeContract.renderTransform, on: element, .identity, then: .rotate(45), with: figure(element)),
            ]
        }
    }

    /// A shape is filled in its colour inside its figure, and in the colour the tree changes it to; a line, which
    /// encloses nothing, shows no fill.
    static func filled(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).isFilledInItsColour", covers: [
            Covered(ShapeContract.fill, on: element), Covered(ButtonContract.clicked),
        ]) { s in
            let blue = State(wrappedValue: false)
            s.start {
                Specimens.page(element, figure(element) + [
                    Write(ShapeContract.fill, Brush.solidColor(blue.wrappedValue ? .blue : .red)),
                    Write(VisualElementContract.width, 40), Write(VisualElementContract.height, 40),
                ], beside: [Button("Blue").onClicked { blue.wrappedValue = true }.id("change")])
            }
            let shape = try s.specimen(element)
            let inside = Point(20, 20)
            guard element != "Line" else {
                s.turn()
                return s.expect(try s.color(of: shape, at: inside), nil, "a line encloses nothing to fill")
            }
            try s.settle { try s.color(of: shape, at: inside) == .red }
            s.expect(try s.color(of: shape, at: inside), .red)

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.color(of: shape, at: inside) == .blue }
            s.expect(try s.color(of: shape, at: inside), .blue, "the colour the tree changed it to")
        }
    }

    /// A shape's outline is drawn in its colour, as wide as the tree says.
    static func outlined(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).isOutlinedInItsColourAndWidth", covers: [
            Covered(ShapeContract.stroke, on: element), Covered(ShapeContract.strokeWidth, on: element),
        ]) { s in
            s.start {
                Specimens.page(element, figure(element) + [
                    Write(ShapeContract.stroke, Brush.solidColor(.red)), Write(ShapeContract.strokeWidth, 8),
                    Write(VisualElementContract.width, 40), Write(VisualElementContract.height, 40),
                ])
            }
            let shape = try s.specimen(element)
            let edge = Self.onOutline(element)
            try s.settle { try s.color(of: shape, at: edge) == .red }
            s.expect(try s.color(of: shape, at: edge), .red, "on its outline")
        }
    }

    /// A figure drawn in its own small numbers is fitted whole into its room, keeping its proportions, or stretched
    /// across it as its aspect says; a rectangle and an ellipse fill their room either way.
    static func placedByItsAspect(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).isPlacedInItsRoomAsItsAspectSays", covers: [
            Covered(ShapeContract.aspect, on: element), Covered(ButtonContract.clicked),
        ]) { s in
            let stretched = State(wrappedValue: false)
            let paint: [any Worn] = element == "Line" || element == "Polyline"
                ? [Write(ShapeContract.stroke, Brush.solidColor(.red)), Write(ShapeContract.strokeWidth, 4)]
                : [Write(ShapeContract.fill, Brush.solidColor(.red))]
            s.start {
                Specimens.page(element, small(element) + paint + [
                    Write(ShapeContract.aspect, stretched.wrappedValue ? Aspect.stretch : .fit),
                    Write(VisualElementContract.width, 80), Write(VisualElementContract.height, 40),
                    Write(ViewContract.horizontalAlignment, Alignment.start),
                ], beside: [Button("Stretch").onClicked { stretched.wrappedValue = true }.id("change")])
            }
            let shape = try s.specimen(element)
            let stroked = element == "Line" || element == "Polyline"
            let probe = stroked ? Point(70, 35) : Point(75, 5)
            let fills = element == "Rectangle" || element == "Ellipse"
            let inside = stroked || fills ? Point(40, 20) : Point(55, 5)
            try s.settle { try s.color(of: shape, at: inside) == .red }
            s.expect(try s.color(of: shape, at: fills ? Point(40, 20) : probe), fills ? .red : nil,
                     fills ? "filling its room" : "fitted, its proportions kept")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.color(of: shape, at: fills ? Point(40, 20) : probe) == .red }
            s.expect(try s.color(of: shape, at: fills ? Point(40, 20) : probe), .red, "stretched across its room")
        }
    }

    /// A shape's transform moves what it draws, as the tree changes it.
    static func movedByItsTransform(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).isMovedByItsTransform", covers: [
            Covered(ShapeContract.renderTransform, on: element), Covered(ButtonContract.clicked),
        ]) { s in
            let moved = State(wrappedValue: false)
            let line = element == "Line"
            let paint: [any Worn] = line
                ? [Write(ShapeContract.stroke, Brush.solidColor(.red)), Write(ShapeContract.strokeWidth, 4)]
                : [Write(ShapeContract.fill, Brush.solidColor(.red))]
            s.start {
                Specimens.page(element, figure(element) + paint + [
                    Write(ShapeContract.renderTransform, moved.wrappedValue
                          ? (line ? ViewTransform.translate(0, 12) : .translate(24, 0)) : .identity),
                    Write(VisualElementContract.width, 40), Write(VisualElementContract.height, 40),
                ], beside: [Button("Move").onClicked { moved.wrappedValue = true }.id("change")])
            }
            let shape = try s.specimen(element)
            let before = line ? Point(20, 20) : Point(8, 20)
            try s.settle { try s.color(of: shape, at: before) == .red }

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.color(of: shape, at: before) == nil }
            s.expect(try s.color(of: shape, at: before), nil, "moved away from where it stood")
        }
    }

    /// A figure in small numbers of its own - ten across - which its aspect places in a larger room.
    static func small(_ element: String) -> [any Worn] {
        switch element {
        case "Line":
            [Write(LineContract.x1, 0), Write(LineContract.y1, 0), Write(LineContract.x2, 10), Write(LineContract.y2, 10)]
        case "Polygon": [Write(PolygonContract.points, [Point(0, 0), Point(10, 0), Point(10, 10)])]
        case "Polyline": [Write(PolylineContract.points, [Point(0, 0), Point(10, 10)])]
        case "Path": [Write(PathContract.data, "M 0 0 L 10 0 L 10 10 Z")]
        default: []
        }
    }

    /// What `element`'s specimen needs to be a figure at all: a line's ends, a polygon's points, a path's data.
    static func figure(_ element: String) -> [any Worn] {
        switch element {
        case "Line":
            [Write(LineContract.x1, 0), Write(LineContract.y1, 20), Write(LineContract.x2, 40), Write(LineContract.y2, 20)]
        case "Polygon":
            [Write(PolygonContract.points, [Point(0, 0), Point(40, 0), Point(40, 40), Point(0, 40)])]
        case "Polyline":
            [Write(PolylineContract.points, [Point(0, 0), Point(40, 0), Point(40, 40), Point(0, 40), Point(0, 0)])]
        case "Path":
            [Write(PathContract.data, "M 0 0 L 40 0 L 40 40 L 0 40 Z"), Write(ShapeContract.aspect, Aspect.stretch)]
        default:
            []
        }
    }

    /// A point on `element`'s outline, eight wide.
    static func onOutline(_ element: String) -> Point {
        element == "Line" ? Point(20, 20) : Point(20, 2)
    }
}
