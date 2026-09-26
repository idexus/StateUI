// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// `RectangleContract` on a host: a rectangle fills its room, its corners rounded away as far as the tree says.
@_spi(Host) public enum RectangleTests: ConformanceFamily {
    public static let name = "Rectangle"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aRectangleFillsItsRoom", covers: [
                Covered(RectangleContract.self), Covered(ShapeContract.fill, on: "Rectangle"),
            ]) { s in
                s.start { VStack { Rectangle().fill(.red).width(100).height(60).id("shape") }.horizontalAlignment(.start) }
                let shape = try s.element("shape")

                try s.settle { try s.color(of: shape, at: Point(50, 30)) == .red }
                s.expect(try s.color(of: shape, at: Point(1, 1)), .red, "to its corner")
                s.expect(try s.color(of: shape, at: Point(99, 59)), .red, "to its other corner")
            },
            ConformanceCase("itsCornersAreRoundedAwayAsTheTreeSays", covers: [
                Covered(RectangleContract.cornerRadius), Covered(ButtonContract.clicked),
            ]) { s in
                let square = State(wrappedValue: false)
                s.start {
                    VStack {
                        Rectangle().fill(.red).cornerRadius(square.wrappedValue ? 0 : 20).width(100).height(60).id("shape")
                        Button("Square").onClicked { square.wrappedValue = true }.id("change")
                    }
                    .horizontalAlignment(.start)
                }
                let shape = try s.element("shape")
                try s.settle { try s.color(of: shape, at: Point(50, 30)) == .red }
                s.expect(try s.color(of: shape, at: Point(1, 1)), nil, "the corner rounded away")
                s.expect(try s.color(of: shape, at: Point(50, 1)), .red, "the edge between the corners")

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.color(of: shape, at: Point(1, 1)) == .red }
                s.expect(try s.color(of: shape, at: Point(1, 1)), .red, "square once the tree says so")
            },
        ]
    }
}
