// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `CorneredShapeContract` on a host: a shape's corners are joined as the tree says, a mitre cut across past its
/// limit, read off what the host draws; each case made for every shape wearing the tier.
/// Design: docs/design/host/conformance.md#a-drawing-read-by-its-colors
@_spi(Host) public enum CorneredShapeTests: ConformanceFamily {
    public static let name = "CorneredShape"

    public static var cases: [ConformanceCase] {
        Specimens.wearing(CorneredShapeContract.self).flatMap { element in
            [
                joined(element), limited(element),
                Aspects.holds(
                    CorneredShapeContract.lineJoin, on: element, .miter, then: .bevel,
                    with: ShapeTests.stroked(element)),
                Aspects.holds(
                    CorneredShapeContract.miterLimit, on: element, 10, then: 4, with: ShapeTests.stroked(element)),
            ]
        }
    }

    /// A corner is mitred to a point, and cut across once the tree bevels it.
    @MainActor
    static func joined(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).joinsItsCornersAsTheTreeSays", proves: [
            Covered(CorneredShapeContract.lineJoin, on: element),
        ], needs: [Covered(ButtonContract.clicked)]) { s in
            let bevelled = State(wrappedValue: false)
            s.start {
                Specimens.page(element, ShapeTests.outlined(element, width: 8) + [
                    Write(CorneredShapeContract.lineJoin, bevelled.wrappedValue ? LineJoin.bevel : .miter),
                    Write(CorneredShapeContract.miterLimit, 10.0),
                ], beside: [Button("Bevel").onClicked { bevelled.wrappedValue = true }.id("change")])
            }
            let tip = Self.cornerTip(element)
            let shape = try s.specimen(element)
            try s.settle { try s.shows(.red, on: shape, at: tip) }
            s.expect(try s.color(of: shape, at: tip), shows: .red, "a mitred corner reaches its point")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.color(of: shape, at: tip) == nil }
            s.expect(try s.color(of: shape, at: tip), nil, "a bevelled one is cut across")
        }
    }

    /// A mitred corner is cut across where its point would reach past the limit the tree sets.
    @MainActor
    static func limited(_ element: String) -> ConformanceCase {
        ConformanceCase("\(element).limitsItsMitresAsTheTreeSays", proves: [
            Covered(CorneredShapeContract.miterLimit, on: element),
        ], needs: [Covered(CorneredShapeContract.lineJoin, on: element), Covered(ButtonContract.clicked)]) { s in
            let limited = State(wrappedValue: false)
            s.start {
                Specimens.page(element, ShapeTests.outlined(element, width: 8) + [
                    Write(CorneredShapeContract.lineJoin, LineJoin.miter),
                    Write(CorneredShapeContract.miterLimit, limited.wrappedValue ? 1.0 : 10.0),
                ], beside: [Button("Limit").onClicked { limited.wrappedValue = true }.id("change")])
            }
            let tip = Self.cornerTip(element)
            let shape = try s.specimen(element)
            try s.settle { try s.shows(.red, on: shape, at: tip) }
            s.expect(try s.color(of: shape, at: tip), shows: .red, "a right angle's mitre within ten")

            try s.perform(.activate, on: s.element("change"))
            try s.settle { try s.color(of: shape, at: tip) == nil }
            s.expect(try s.color(of: shape, at: tip), nil, "cut across past a limit of one")
        }
    }

    /// A point just inside the outer side of a corner, eight wide, that a mitre covers and a bevel leaves bare.
    static func cornerTip(_ element: String) -> Point {
        element == "Rectangle" ? Point(0, 0) : Point(35, 5)
    }
}
