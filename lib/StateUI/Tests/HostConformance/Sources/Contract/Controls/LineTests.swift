// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// `LineContract` on a host: a line is drawn from its start to its end, nowhere past them, and anew where the tree
/// moves an end - drawn at its own size in the middle of its room, where its numbers stand as written.
@_spi(Host) public enum LineTests: ConformanceFamily {
    public static let name = "Line"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aLineIsDrawnFromItsStartToItsEnd", covers: [
                Covered(LineContract.self), Covered(LineContract.x1), Covered(LineContract.y1), Covered(LineContract.x2),
                Covered(LineContract.y2),
            ]) { s in
                s.start {
                    VStack {
                        Line().x1(10).y1(20).x2(90).y2(20).stroke(.red).strokeWidth(4).aspect(.center)
                            .width(100).height(40).id("shape")
                    }
                    .horizontalAlignment(.start)
                }
                let shape = try s.element("shape")

                try s.settle { try s.color(of: shape, at: Point(50, 20)) == .red }
                s.expect(try s.color(of: shape, at: Point(12, 20)), .red, "from its start")
                s.expect(try s.color(of: shape, at: Point(88, 20)), .red, "to its end")
                s.expect(try s.color(of: shape, at: Point(5, 20)), nil, "nothing before its start")
                s.expect(try s.color(of: shape, at: Point(95, 20)), nil, "nothing past its end")
                s.expect(try s.color(of: shape, at: Point(50, 30)), nil, "nothing beside it")
            },
            ConformanceCase("anEndTheTreeMovesDrawsTheLineAnew", covers: [
                Covered(LineContract.x2), Covered(LineContract.y2), Covered(ButtonContract.clicked),
            ]) { s in
                let down = State(wrappedValue: false)
                s.start {
                    VStack {
                        Line().x1(10).y1(down.wrappedValue ? 2 : 20).x2(90).y2(down.wrappedValue ? 38 : 20)
                            .stroke(.red).strokeWidth(4).aspect(.center).width(100).height(40).id("shape")
                        Button("Down").onClicked { down.wrappedValue = true }.id("change")
                    }
                    .horizontalAlignment(.start)
                }
                let shape = try s.element("shape")
                try s.settle { try s.color(of: shape, at: Point(50, 20)) == .red }

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.color(of: shape, at: Point(30, 11)) == .red }
                s.expect(try s.color(of: shape, at: Point(30, 20)), nil, "the old line gone")
                s.expect(try s.color(of: shape, at: Point(70, 29)), .red, "the new one drawn")
            },
        ]
    }
}
