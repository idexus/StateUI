// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `PolygonContract` on a host: a polygon is filled inside its points, drawn anew where the tree moves them, and a
/// figure crossing itself is filled by its rule.
@_spi(Host) public enum PolygonTests: ConformanceFamily {
    public static let name = "Polygon"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aPolygonIsFilledInsideItsPoints", covers: [
                Covered(PolygonContract.self), Covered(PolygonContract.points), Covered(ButtonContract.clicked),
            ]) { s in
                let moved = State(wrappedValue: false)
                s.start {
                    VStack {
                        Polygon(moved.wrappedValue
                                ? [Point(40, 0), Point(40, 40), Point(0, 40)]
                                : [Point(0, 0), Point(40, 0), Point(0, 40)])
                            .fill(.blue).aspect(.center).width(40).height(40).id("shape")
                        Button("Move").onClicked { moved.wrappedValue = true }.id("change")
                    }
                    .horizontalAlignment(.start)
                }
                let shape = try s.element("shape")
                try s.settle { try s.color(of: shape, at: Point(8, 8)) == .blue }
                s.expect(try s.color(of: shape, at: Point(32, 32)), nil, "outside its points")

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.color(of: shape, at: Point(32, 32)) == .blue }
                s.expect(try s.color(of: shape, at: Point(8, 8)), nil, "the points the tree moved")
            },
            ConformanceCase("aFigureCrossingItselfIsFilledByItsRule", covers: [
                Covered(PolygonContract.fillRule), Covered(PolygonContract.points), Covered(ButtonContract.clicked),
            ]) { s in
                let rule = State(wrappedValue: FillRule.evenOdd)
                s.start {
                    VStack {
                        Polygon(Self.woundTwice).fillRule(rule.wrappedValue).fill(.blue).aspect(.center)
                            .width(40).height(40).id("shape")
                        Button("Nonzero").onClicked { rule.wrappedValue = .nonzero }.id("change")
                    }
                    .horizontalAlignment(.start)
                }
                let shape = try s.element("shape")
                try s.settle { try s.color(of: shape, at: Point(2, 2)) == .blue }
                s.expect(try s.color(of: shape, at: Point(20, 20)), nil, "even and odd: the middle, gone round twice, empty")

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.color(of: shape, at: Point(20, 20)) == .blue }
                s.expect(try s.color(of: shape, at: Point(20, 20)), .blue, "nonzero: the middle filled")
            },
        ]
    }

    /// A square gone round, then its middle gone round the same way again: its middle wound twice.
    static let woundTwice = [
        Point(0, 0), Point(40, 0), Point(40, 40), Point(0, 40), Point(0, 0),
        Point(10, 10), Point(30, 10), Point(30, 30), Point(10, 30), Point(10, 10),
    ]
}
