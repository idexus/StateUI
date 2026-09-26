// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `PathContract` on a host: a path is filled inside the figure its data draws, and drawn again when the tree changes
/// its data.
@_spi(Host) public enum PathTests: ConformanceFamily {
    public static let name = "Path"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aPathIsFilledInsideTheFigureItsDataDraws", covers: [
                Covered(PathContract.self), Covered(PathContract.data), Covered(ButtonContract.clicked),
            ]) { s in
                let flipped = State(wrappedValue: false)
                s.start {
                    VStack {
                        Path(flipped.wrappedValue ? "M 0 40 L 40 40 L 40 0 Z" : "M 0 0 L 40 0 L 0 40 Z")
                            .fill(.red).aspect(.stretch).width(40).height(40).id("shape")
                        Button("Flip").onClicked { flipped.wrappedValue = true }.id("change")
                    }
                    .horizontalAlignment(.start)
                }
                let shape = try s.element("shape")
                try s.settle { try s.color(of: shape, at: Point(5, 5)) == .red }
                s.expect(try s.color(of: shape, at: Point(35, 35)), nil, "outside the triangle")

                try s.perform(.activate, on: s.element("change"))
                try s.settle { try s.color(of: shape, at: Point(35, 35)) == .red }
                s.expect(try s.color(of: shape, at: Point(5, 5)), nil, "the new figure's outside")
            },
        ]
    }
}
