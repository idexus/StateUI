// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// `ActivityIndicatorContract` on a host: a spinner turns while its work runs, and stops when the tree says so.
@_spi(Host) public enum ActivityIndicatorTests: ConformanceFamily {
    public static let name = "ActivityIndicator"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aSpinnerTurnsWhileItsWorkRuns", covers: [
                Covered(ActivityIndicatorContract.self), Covered(ActivityIndicatorContract.isRunning),
                Covered(ButtonContract.clicked),
            ]) { s in
                let running = State(wrappedValue: true)
                s.start {
                    VStack {
                        ActivityIndicator(running.wrappedValue).id("spinner")
                        Button("Stop").onClicked { running.wrappedValue = false }.id("stop")
                    }
                }
                let spinner = try s.element("spinner")
                s.expect(try s.held(ActivityIndicatorContract.isRunning, on: spinner), true)

                try s.perform(.activate, on: s.element("stop"))
                try s.settle { try s.held(ActivityIndicatorContract.isRunning, on: spinner) == false }

                s.expect(try s.held(ActivityIndicatorContract.isRunning, on: spinner), false)
            },
            Aspects.holds(ActivityIndicatorContract.isRunning, on: "ActivityIndicator", false, then: true),
        ]
    }
}
