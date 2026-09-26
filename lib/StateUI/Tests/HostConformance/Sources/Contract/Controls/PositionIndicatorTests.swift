// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// `PositionIndicatorContract` on a host: as many marks as the tree counts - no more than it lets show, none where
/// one alone is hidden - the one at the position picked out, in the colours, size and shape the tree gives them.
@_spi(Host) public enum PositionIndicatorTests: ConformanceFamily {
    public static let name = "PositionIndicator"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("anIndicatorShowsItsMarksAndItsPosition", covers: [
                Covered(PositionIndicatorContract.self), Covered(PositionIndicatorContract.count),
                Covered(PositionIndicatorContract.position),
            ]) { s in
                s.start { VStack { PositionIndicator().count(5).position(2).id("indicator") } }
                let indicator = try s.element("indicator")

                s.expect(try s.held(PositionIndicatorContract.count, on: indicator), 5)
                s.expect(try s.held(PositionIndicatorContract.position, on: indicator), 2)
            },
            Aspects.holds(PositionIndicatorContract.count, on: "PositionIndicator", 3, then: 6),
            Aspects.holds(PositionIndicatorContract.position, on: "PositionIndicator", 0, then: 2,
                          with: [Write(PositionIndicatorContract.count, 4)]),
            Aspects.holds(PositionIndicatorContract.maximumVisible, on: "PositionIndicator", 3, then: 5,
                          with: [Write(PositionIndicatorContract.count, 8)]),
            Aspects.holds(PositionIndicatorContract.hideSingle, on: "PositionIndicator", true, then: false,
                          with: [Write(PositionIndicatorContract.count, 1)]),
            Aspects.holds(PositionIndicatorContract.indicatorColor, on: "PositionIndicator", .gray, then: .red,
                          with: [Write(PositionIndicatorContract.count, 3)]),
            Aspects.holds(PositionIndicatorContract.selectedIndicatorColor, on: "PositionIndicator", .black, then: .blue,
                          with: [Write(PositionIndicatorContract.count, 3)]),
            Aspects.holds(PositionIndicatorContract.indicatorSize, on: "PositionIndicator", 6, then: 10,
                          with: [Write(PositionIndicatorContract.count, 3)]),
            Aspects.holds(PositionIndicatorContract.indicatorsShape, on: "PositionIndicator", .circle, then: .square,
                          with: [Write(PositionIndicatorContract.count, 3)]),
        ]
    }
}
