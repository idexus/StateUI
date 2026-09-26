// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// `ProgressBarContract` on a host: a bar stands at its share of the work, within its ends.
@_spi(Host) public enum ProgressBarTests: ConformanceFamily {
    public static let name = "ProgressBar"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aBarStandsAtItsShareOfTheWorkWithinItsEnds", covers: [
                Covered(ProgressBarContract.self), Covered(ProgressBarContract.progress),
            ]) { s in
                s.start {
                    VStack {
                        ProgressBar(0.5).id("half")
                        ProgressBar(1.5).id("over")
                        ProgressBar(-1).id("under")
                    }
                }

                s.expect(try s.held(ProgressBarContract.progress, on: s.element("half")), 0.5, within: 1e-9)
                s.expect(try s.held(ProgressBarContract.progress, on: s.element("over")), 1, within: 1e-9)
                s.expect(try s.held(ProgressBarContract.progress, on: s.element("under")), 0, within: 1e-9)
            },
            Aspects.holds(ProgressBarContract.progress, on: "ProgressBar", 0.25, then: 0.75),
        ]
    }
}
