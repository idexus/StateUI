// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `LineContract` on a host: a line is drawn from its start to its end, nowhere past them, and anew where the tree
/// moves its ends - drawn at its own size in the middle of its room, where its numbers stand as written.
@_spi(Host) public enum LineTests: ConformanceFamily {
    public static let name = "Line"

    public static var cases: [ConformanceCase] {
        [
            Aspects.standsAlone("Line"),
            ConformanceCase("aLineIsDrawnFromItsStartToItsEnd", proves: [
                Covered(LineContract.from), Covered(LineContract.to),
            ]) { s in
                s.start {
                    VStack {
                        Line(from: Point(10, 20), to: Point(90, 20)).stroke(.red).lineWidth(4).contentMode(.center)
                            .width(100).height(40).id("shape")
                    }
                    .horizontalAlignment(.start)
                }
                let shape = try s.element("shape")

                try s.settle { try s.shows(.red, on: shape, at: Point(50, 20)) }
                s.expect(try s.color(of: shape, at: Point(12, 20)), shows: .red, "from its start")
                s.expect(try s.color(of: shape, at: Point(88, 20)), shows: .red, "to its end")
                s.expect(try s.color(of: shape, at: Point(5, 20)), nil, "nothing before its start")
                s.expect(try s.color(of: shape, at: Point(95, 20)), nil, "nothing past its end")
                s.expect(try s.color(of: shape, at: Point(50, 30)), nil, "nothing beside it")
            },
            ConformanceCase("endsTheTreeMovesDrawTheLineAnew", proves: [
                Covered(LineContract.from), Covered(LineContract.to),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
                let down = State(wrappedValue: false)
                s.start {
                    VStack {
                        Line(from: Point(10, down.wrappedValue ? 2 : 20), to: Point(90, down.wrappedValue ? 38 : 20))
                            .stroke(.red).lineWidth(4).contentMode(.center).width(100).height(40).id("shape")
                        Button("Down").onClicked { down.wrappedValue = true }.id("change")
                    }
                    .horizontalAlignment(.start)
                }
                let shape = try s.element("shape")
                try s.settle { try s.shows(.red, on: shape, at: Point(50, 20)) }

                try s.perform(.activate, on: s.element("change"))
                // The ends travel to their new places: the line has arrived once both points it passes are drawn.
                try s.settle {
                    try s.shows(.red, on: shape, at: Point(30, 11)) && s.shows(.red, on: shape, at: Point(70, 29))
                }
                s.expect(try s.color(of: shape, at: Point(30, 20)), nil, "the old line gone")
                s.expect(try s.color(of: shape, at: Point(70, 29)), shows: .red, "the new one drawn")
            },
        ]
    }
}
