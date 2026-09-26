// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// `PolylineContract` on a host: a polyline is drawn through its points, anew where the tree moves them, and filled by
/// its rule.
@_spi(Host) public enum PolylineTests: ConformanceFamily {
    public static let name = "Polyline"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aPolylineIsDrawnThroughItsPoints", covers: [
                Covered(PolylineContract.self), Covered(PolylineContract.points), Covered(ButtonContract.clicked),
            ]) { s in
                let moved = State(wrappedValue: false)
                s.start {
                    VStack {
                        Polyline(moved.wrappedValue ? [Point(0, 30), Point(40, 30)] : [Point(0, 10), Point(40, 10)])
                            .stroke(.red).strokeWidth(4).aspect(.center).width(40).height(40).id("shape")
                        Button("Move").onClicked { moved.wrappedValue = true }.id("change")
                    }
                    .horizontalAlignment(.start)
                }
                let shape = try s.element("shape")
                try s.settle { try s.color(of: shape, at: Point(20, 10)) == .red }
                s.expect(try s.color(of: shape, at: Point(20, 30)), nil, "nowhere else")

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.color(of: shape, at: Point(20, 30)) == .red }
                s.expect(try s.color(of: shape, at: Point(20, 10)), nil, "the points the tree moved")
            },
            ConformanceCase("aFilledPolylineCrossingItselfIsFilledByItsRule", covers: [
                Covered(PolylineContract.fillRule), Covered(ButtonContract.clicked),
            ]) { s in
                let rule = State(wrappedValue: FillRule.evenOdd)
                s.start {
                    VStack {
                        Polyline(PolygonTests.woundTwice).fillRule(rule.wrappedValue).fill(.blue).aspect(.center)
                            .width(40).height(40).id("shape")
                        Button("Nonzero").onClicked { rule.wrappedValue = .nonzero }.id("change")
                    }
                    .horizontalAlignment(.start)
                }
                let shape = try s.element("shape")
                try s.settle { try s.color(of: shape, at: Point(2, 2)) == .blue }
                s.expect(try s.color(of: shape, at: Point(20, 20)), nil, "even and odd: the middle empty")

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.color(of: shape, at: Point(20, 20)) == .blue }
                s.expect(try s.color(of: shape, at: Point(20, 20)), .blue, "nonzero: the middle filled")
            },
        ]
    }
}
