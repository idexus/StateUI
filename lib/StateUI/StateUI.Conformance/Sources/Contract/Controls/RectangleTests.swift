// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `RectangleContract` on a host: a rectangle fills its room, its corners rounded away as far as the tree says, and a
/// fill from a state takes each color the state turns to.
@_spi(Host) public enum RectangleTests: ConformanceFamily {
    public static let name = "Rectangle"

    public static var cases: [ConformanceCase] {
        [
            Aspects.standsAlone("Rectangle"),
            ConformanceCase("aRectangleFillsItsRoom", proves: [
                Covered(RectangleContract.self),
            ], needs: [Covered(FilledShapeContract.fill, on: "Rectangle")]) { s in
                s.start { VStack {
                    Rectangle()
                        .fill(.red)
                        .width(100)
                        .height(60)
                        .id("shape")
                }.horizontalAlignment(.start) }
                let shape = try s.element("shape")

                try s.settle { try s.shows(.red, on: shape, at: Point(50, 30)) }
                s.expect(try s.color(of: shape, at: Point(1, 1)), shows: .red, "to its corner")
                s.expect(try s.color(of: shape, at: Point(99, 59)), shows: .red, "to its other corner")
            },
            ConformanceCase("itsCornersAreRoundedAwayAsTheTreeSays", proves: [
                Covered(RectangleContract.cornerRadius),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let square = State(wrappedValue: false)
                s.start {
                    VStack {
                        Rectangle()
                            .fill(.red)
                            .cornerRadius(square.wrappedValue ? 0 : 20)
                            .width(100)
                            .height(60)
                            .id("shape")
                        Button("Square").onClicked { square.wrappedValue = true }.id("change")
                    }
                    .horizontalAlignment(.start)
                }
                let shape = try s.element("shape")
                try s.settle { try s.shows(.red, on: shape, at: Point(50, 30)) }
                s.expect(try s.color(of: shape, at: Point(1, 1)), nil, "the corner rounded away")
                s.expect(try s.color(of: shape, at: Point(50, 1)), shows: .red, "the edge between the corners")

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.shows(.red, on: shape, at: Point(1, 1)) }
                s.expect(try s.color(of: shape, at: Point(1, 1)), shows: .red, "square once the tree says so")
            },
            ConformanceCase("aFillFromAStateTakesTheColorItTurnsTo", proves: [
                Covered(RectangleContract.self),
            ], needs: [Covered(FilledShapeContract.fill, on: "Rectangle"), Covered(ButtonContract.clicked)]) { s in
                let color = State(wrappedValue: Color.red)
                s.start {
                    VStack {
                        Rectangle()
                            .fill(color.projectedValue)
                            .width(100)
                            .height(60)
                            .id("shape")
                        Button("Blue").onClicked { color.wrappedValue = .blue }.id("change")
                    }
                    .horizontalAlignment(.start)
                }
                let shape = try s.element("shape")
                try s.settle { try s.shows(.red, on: shape, at: Point(50, 30)) }

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.shows(.blue, on: shape, at: Point(50, 30)) }
                s.expect(try s.color(of: shape, at: Point(50, 30)), shows: .blue, "the color the state turned to")
            },
        ]
    }
}
