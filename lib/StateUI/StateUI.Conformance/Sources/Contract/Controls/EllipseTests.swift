// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `EllipseContract` on a host: an ellipse fills its room inside its curve, and nothing beyond it.
@_spi(Host) public enum EllipseTests: ConformanceFamily {
    public static let name = "Ellipse"

    public static var cases: [ConformanceCase] {
        [
            Aspects.standsAlone("Ellipse"),
            ConformanceCase("anEllipseFillsItsRoomInsideItsCurve", proves: [
                Covered(EllipseContract.self),
            ], needs: [Covered(FilledShapeContract.fill, on: "Ellipse")]) { s in
                s.start { VStack {
                    Ellipse()
                        .fill(.red)
                        .width(100)
                        .height(60)
                        .id("shape")
                }.horizontalAlignment(.start) }
                let shape = try s.element("shape")

                try s.settle { try s.shows(.red, on: shape, at: Point(50, 30)) }
                s.expect(try s.color(of: shape, at: Point(50, 30)), shows: .red, "its middle")
                s.expect(try s.color(of: shape, at: Point(5, 30)), shows: .red, "its left, inside the curve")
                s.expect(try s.color(of: shape, at: Point(3, 3)), nil, "its corner, beyond the curve")
            },
        ]
    }
}
