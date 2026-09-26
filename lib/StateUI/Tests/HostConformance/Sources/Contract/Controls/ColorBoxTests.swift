// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// `ColorBoxContract` on a host: a box fills its room with its colour, the colour the tree changes it to, and leaves
/// its rounded corners empty.
@_spi(Host) public enum ColorBoxTests: ConformanceFamily {
    public static let name = "ColorBox"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aBoxFillsItsRoomWithItsColour", covers: [
                Covered(ColorBoxContract.self), Covered(ColorBoxContract.color), Covered(ButtonContract.clicked),
            ]) { s in
                let blue = State(wrappedValue: false)
                s.start {
                    VStack {
                        ColorBox(blue.wrappedValue ? .blue : .red).width(40).height(40).id("box")
                        Button("Blue").onClicked { blue.wrappedValue = true }.id("change")
                    }
                    .horizontalAlignment(.start)
                }
                let box = try s.element("box")
                try s.settle { try s.color(of: box, at: Point(20, 20)) == .red }
                s.expect(try s.color(of: box, at: Point(1, 1)), .red, "to its corner")

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.color(of: box, at: Point(20, 20)) == .blue }
                s.expect(try s.color(of: box, at: Point(20, 20)), .blue, "the colour the tree changed it to")
            },
            ConformanceCase("aBoxsRoundedCornersAreLeftEmpty", covers: [
                Covered(ColorBoxContract.cornerRadius), Covered(ColorBoxContract.color), Covered(ButtonContract.clicked),
            ]) { s in
                let square = State(wrappedValue: false)
                s.start {
                    VStack {
                        ColorBox(.red).cornerRadius(square.wrappedValue ? 0 : 20)
                            .width(80).height(80).id("box")
                        Button("Square").onClicked { square.wrappedValue = true }.id("change")
                    }
                    .horizontalAlignment(.start)
                }
                let box = try s.element("box")
                try s.settle { try s.color(of: box, at: Point(40, 40)) == .red }
                s.expect(try s.color(of: box, at: Point(1, 1)), nil, "the rounded corner empty")

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.color(of: box, at: Point(1, 1)) == .red }
                s.expect(try s.color(of: box, at: Point(1, 1)), .red, "square once the tree says so")
            },
        ]
    }
}
