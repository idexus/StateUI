// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `CapsuleContract` on a host: a capsule's ends round whole at every size - half its shorter side - its long sides
/// straight, and nothing stands beyond its ends.
@_spi(Host) public enum CapsuleTests: ConformanceFamily {
    public static let name = "Capsule"

    public static var cases: [ConformanceCase] {
        [
            Aspects.standsAlone("Capsule"),
            ConformanceCase("aCapsuleRoundsItsEndsWholeAtEverySize", proves: [
                Covered(CapsuleContract.self),
            ], needs: [Covered(FilledShapeContract.fill, on: "Capsule"), Covered(ButtonContract.clicked)]) { s in
                let tall = State(wrappedValue: false)
                s.start {
                    VStack {
                        Capsule().fill(.red).width(tall.wrappedValue ? 40 : 100).height(tall.wrappedValue ? 100 : 40).id("shape")
                        Button("Stand").onClicked { tall.wrappedValue = true }.id("change")
                    }
                    .horizontalAlignment(.start)
                }
                let shape = try s.element("shape")

                try s.settle { try s.shows(.red, on: shape, at: Point(50, 20)) }
                s.expect(try s.color(of: shape, at: Point(50, 20)), shows: .red, "its middle")
                s.expect(try s.color(of: shape, at: Point(4, 20)), shows: .red, "its left end, round to its middle")
                s.expect(try s.color(of: shape, at: Point(3, 3)), nil, "its corner, beyond its round end")
                s.expect(try s.color(of: shape, at: Point(25, 2)), shows: .red, "its long side, straight where an oval curves")

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.shows(.red, on: shape, at: Point(20, 80)) }
                s.expect(try s.color(of: shape, at: Point(20, 4)), shows: .red, "its top end, round to its middle")
                s.expect(try s.color(of: shape, at: Point(3, 3)), nil, "its corner, beyond its round end")
                s.expect(try s.color(of: shape, at: Point(2, 25)), shows: .red, "its long side, straight where an oval curves")
            },
        ]
    }
}
