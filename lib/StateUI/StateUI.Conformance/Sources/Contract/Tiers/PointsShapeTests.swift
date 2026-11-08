// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `PointsShapeContract` on a host: a shape drawn through points follows the points the tree gives it, and fills a
/// self-crossing outline as its rule says - a polygon, a polyline.
@_spi(Host) public enum PointsShapeTests: ConformanceFamily {
    public static let name = "PointsShape"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("Polygon.aPolygonIsFilledInsideItsPoints", proves: [
                Covered(PointsShapeContract.points, on: PolygonContract.self),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
                let moved = State(wrappedValue: false)
                s.start {
                    VStack {
                        Polygon(moved.wrappedValue
                                ? [Point(40, 0), Point(40, 40), Point(0, 40)]
                                : [Point(0, 0), Point(40, 0), Point(0, 40)])
                            .fill(.blue).contentMode(.center).width(40).height(40).id("shape")
                        Button("Move").onClicked { moved.wrappedValue = true }.id("change")
                    }
                    .horizontalAlignment(.start)
                }
                let shape = try s.element("shape")
                try s.settle { try s.shows(.blue, on: shape, at: Point(8, 8)) }
                s.expect(try s.color(of: shape, at: Point(32, 32)), nil, "outside its points")

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.shows(.blue, on: shape, at: Point(32, 32)) }
                s.expect(try s.color(of: shape, at: Point(8, 8)), nil, "the points the tree moved")
            },
            ConformanceCase("Polygon.aFigureCrossingItselfIsFilledByItsRule", proves: [
                Covered(PointsShapeContract.fillRule, on: PolygonContract.self), Covered(PointsShapeContract.points, on: PolygonContract.self),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
                let rule = State(wrappedValue: FillRule.evenOdd)
                s.start {
                    VStack {
                        Polygon(PolygonTests.woundTwice).fillRule(rule.wrappedValue).fill(.blue).contentMode(.center)
                            .width(40).height(40).id("shape")
                        Button("Nonzero").onClicked { rule.wrappedValue = .nonzero }.id("change")
                    }
                    .horizontalAlignment(.start)
                }
                let shape = try s.element("shape")
                try s.settle { try s.shows(.blue, on: shape, at: Point(2, 2)) }
                s.expect(try s.color(of: shape, at: Point(20, 20)), nil, "even and odd: the middle, gone round twice, empty")

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.shows(.blue, on: shape, at: Point(20, 20)) }
                s.expect(try s.color(of: shape, at: Point(20, 20)), shows: .blue, "nonzero: the middle filled")
            },
            ConformanceCase("Polyline.aPolylineIsDrawnThroughItsPoints", proves: [
                Covered(PointsShapeContract.points, on: PolylineContract.self),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
                let moved = State(wrappedValue: false)
                s.start {
                    VStack {
                        // Down the two sides, the figure as tall as its room, and across at the height read.
                        Polyline(moved.wrappedValue ? PolylineTests.across(at: 30) : PolylineTests.across(at: 10))
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
            ConformanceCase("Polyline.aFilledPolylineCrossingItselfIsFilledByItsRule", proves: [
                Covered(PointsShapeContract.fillRule, on: PolylineContract.self),
            ], needs: [Covered(ClickElementContract.clicked, on: ButtonContract.self)]) { s in
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
}
