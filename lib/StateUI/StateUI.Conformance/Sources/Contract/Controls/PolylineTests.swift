// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `PolylineContract` on a host: a polyline is drawn through its points, anew where the tree moves them, and filled by
/// its rule.
@_spi(Host) public enum PolylineTests: ConformanceFamily {
    public static let name = "Polyline"

    public static var cases: [ConformanceCase] {
        [
            Aspects.standsAlone("Polyline"),
            ConformanceCase("aPolylineIsDrawnThroughItsPoints", proves: [
                Covered(PolylineContract.points),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let moved = State(wrappedValue: false)
                s.start {
                    VStack {
                        // Down the two sides, the figure as tall as its room, and across at the height read.
                        Polyline(moved.wrappedValue ? Self.across(at: 30) : Self.across(at: 10))
                            .stroke(.red).lineWidth(4).contentMode(.center).width(40).height(40).id("shape")
                        Button("Move").onClicked { moved.wrappedValue = true }.id("change")
                    }
                    .horizontalAlignment(.start)
                }
                let shape = try s.element("shape")
                try s.settle { try s.shows(.red, on: shape, at: Point(20, 10)) }
                s.expect(try s.color(of: shape, at: Point(20, 10)), shows: .red, "through its points")
                s.expect(try s.color(of: shape, at: Point(20, 30)), nil, "nowhere else")

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.shows(.red, on: shape, at: Point(20, 30)) }
                s.expect(try s.color(of: shape, at: Point(20, 30)), shows: .red, "through the points the tree moved")
                s.expect(try s.color(of: shape, at: Point(20, 10)), nil, "the points the tree moved")
            },
            ConformanceCase("aFilledPolylineCrossingItselfIsFilledByItsRule", proves: [
                Covered(PolylineContract.fillRule),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let rule = State(wrappedValue: FillRule.evenOdd)
                s.start {
                    VStack {
                        Polyline(PolygonTests.woundTwice).fillRule(rule.wrappedValue).fill(.blue).contentMode(.center)
                            .width(40).height(40).id("shape")
                        Button("Nonzero").onClicked { rule.wrappedValue = .nonzero }.id("change")
                    }
                    .horizontalAlignment(.start)
                }
                let shape = try s.element("shape")
                try s.settle { try s.shows(.blue, on: shape, at: Point(2, 2)) }
                s.expect(try s.color(of: shape, at: Point(20, 20)), nil, "even and odd: the middle empty")

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.shows(.blue, on: shape, at: Point(20, 20)) }
                s.expect(try s.color(of: shape, at: Point(20, 20)), shows: .blue, "nonzero: the middle filled")
            },
        ]
    }

    /// A run down the left side to `y`, across the room at `y`, and down the right side: as tall and wide as the
    /// room its figure stands in, so the points read are the room's own.
    static func across(at y: Double) -> [Point] {
        [Point(0, 0), Point(0, y), Point(40, y), Point(40, 40)]
    }
}
