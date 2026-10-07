// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A layout's and a button's box read off its colours on every host: its fill, its outline in its colour and width,
/// and the shape the outline follows. A button's own face may stand inside an outline, a layout's nothing.
/// Design: docs/design/host/conformance.md#a-drawing-read-by-its-colours
extension BorderElementTests {
    /// The layouts, whose box StateUI draws, and a button.
    static let drawnBoxes: Set<String> = ["Button", "Grid", "HStack", "ScrollView", "VStack", "ZStack"]

    /// Whether `color`, inside `element`'s outline, is none of the outline: nothing at all in a layout, anything but
    /// the outline's red where a button's own face stands.
    static func bare(_ color: Color?, inside element: String) -> Bool {
        element == "Button" ? color != .red : color == nil
    }

    /// The box cases of a layout.
    static func boxCases(_ element: String) -> [ConformanceCase] {
        guard drawnBoxes.contains(element) else { return [] }
        return [boxFilled(element), boxOutlined(element), boxWidened(element), boxShaped(element)]
    }

    /// A layout's box is filled in its background.
    static func boxFilled(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).fillsItsBoxInItsBackground", proves: [
            Covered(VisualElementContract.background, on: element),
        ]) { s in
            s.start { VStack { Specimens.view(element, room + [Write(VisualElementContract.background, .color(.red))]) } }
            let layout = try s.specimen(element)
            try s.settle { try s.shows(.red, on: layout, at: Point(30, 20)) }
            s.expect(try s.color(of: layout, at: Point(30, 20)), shows: .red, "inside its box")
        }
    }

    /// A layout's box is outlined at its edge in its stroke, and nowhere inside.
    static func boxOutlined(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).outlinesItsBoxInItsStroke", proves: [
            Covered(BorderElementContract.stroke, on: element),
        ]) { s in
            s.start { VStack { Specimens.view(element, room + outline(width: 2)) } }
            let layout = try s.specimen(element)
            try s.settle { try s.shows(.red, on: layout, at: Point(1, 20)) }
            s.expect(try s.color(of: layout, at: Point(1, 20)), shows: .red, "at its edge")
            s.expect(bare(try s.color(of: layout, at: Point(30, 20)), inside: element), true, "nothing of it inside")
        }
    }

    /// A wider outline reaches further in from the box's edge.
    static func boxWidened(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).outlinesItsBoxAsWideAsTheTreeSays", proves: [
            Covered(BorderElementContract.lineWidth, on: element),
        ], needs: [Covered(BorderElementContract.stroke, on: element), Covered(ButtonContract.clicked)]) { s in
            let wide = State(wrappedValue: false)
            s.start {
                VStack {
                    Specimens.view(element, room + outline(width: wide.wrappedValue ? 8 : 2))
                    Button("Widen").onClicked { wide.wrappedValue = true }.id("change")
                }
            }
            let layout = try s.specimen(element)
            let inward = Point(5, 20)
            try s.settle { try s.shows(.red, on: layout, at: Point(1, 20)) }
            s.expect(bare(try s.color(of: layout, at: inward), inside: element), true, "two wide stops short of it")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.shows(.red, on: layout, at: inward) }
            s.expect(try s.color(of: layout, at: inward), shows: .red, "eight wide reaches it")
        }
    }

    /// A box outlined as an ellipse leaves its corners bare, which a rectangle's outline covers.
    static func boxShaped(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).outlinesItsBoxInItsShape", proves: [
            Covered(BorderElementContract.shape, on: element),
        ], needs: [Covered(BorderElementContract.stroke, on: element), Covered(ButtonContract.clicked)]) { s in
            let round = State(wrappedValue: false)
            s.start {
                VStack {
                    Specimens.view(element, room + outline(width: 4) + [
                        Write(BorderElementContract.shape, round.wrappedValue ? ContainerShape.ellipse : .rectangle),
                    ])
                    Button("Round").onClicked { round.wrappedValue = true }.id("change")
                }
            }
            let layout = try s.specimen(element)
            let corner = Point(1, 1)
            try s.settle { try s.shows(.red, on: layout, at: corner) }
            s.expect(try s.color(of: layout, at: corner), shows: .red, "a rectangle's corner")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.color(of: layout, at: corner) == nil }
            s.expect(try s.color(of: layout, at: corner), nil, "an ellipse leaves it bare")
        }
    }

    /// A box of 60 by 40 at the top left.
    private static var room: [any Worn] {
        [
            Write(VisualElementContract.width, 60), Write(VisualElementContract.height, 40),
            Write(ViewContract.horizontalAlignment, Alignment.start),
        ]
    }

    /// An outline in red, `width` wide.
    private static func outline(width: Double) -> [any Worn] {
        [Write(BorderElementContract.stroke, Brush.solidColor(.red)), Write(BorderElementContract.lineWidth, width)]
    }
}
