// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `SpinnerContract` on a host: a spinner turns while its work runs, and stops when the tree says so.
@_spi(Host) public enum SpinnerTests: ConformanceFamily {
    public static let name = "Spinner"

    public static var cases: [ConformanceCase] {
        [
            Aspects.standsAlone("Spinner"),
            ConformanceCase("aSpinnerTurnsWhileItsWorkRuns", proves: [
                Covered(SpinnerContract.isAnimating),
            ], needs: [Covered(ButtonContract.clicked)]) { s in
                let running = State(wrappedValue: true)
                s.start {
                    VStack {
                        Spinner(running.wrappedValue).id("spinner")
                        Button("Stop").onClicked { running.wrappedValue = false }.id("stop")
                    }
                }
                let spinner = try s.element("spinner")
                s.expect(try s.held(SpinnerContract.isAnimating, on: spinner), true)

                try s.perform(.activate, on: s.element("stop"))
                try s.settle { try s.held(SpinnerContract.isAnimating, on: spinner) == false }

                s.expect(try s.held(SpinnerContract.isAnimating, on: spinner), false)
            },
            Aspects.holds(SpinnerContract.isAnimating, on: "Spinner", false, then: true),
        ]
    }
}
