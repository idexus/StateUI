// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// A runtime's start, in the one order every host keeps.
@MainActor
final class HostStartTests: XCTestCase {
    /// The environment is told before the kept values are read - reading their keys makes the application, which
    /// is made knowing the device - and the windows come before the turns that render them.
    func testAStartTellsTheEnvironmentBeforeTheKeptValuesAndTheWindowsBeforeTheTurns() {
        let runtime = HostRuntime.still()
        var steps: [String] = []

        runtime.start(
            realizing: HostRealization(elements: [], members: []), unrealized: [],
            environment: { steps.append("environment") }, kept: { steps.append("kept") },
            windows: { steps.append("windows") }, turns: { steps.append("turns") })

        XCTAssertEqual(steps, ["environment", "kept", "windows", "turns"])
    }

    /// The tree stands in the language's direction from the start, before any window comes.
    func testAStartFollowsTheLanguagesDirection() {
        let runtime = HostRuntime.still()
        var directionAtWindows: LayoutDirection?

        runtime.start(
            realizing: HostRealization(elements: [], members: []), unrealized: [], environment: {},
            windows: { directionAtWindows = runtime.tree.languageDirection })

        XCTAssertEqual(directionAtWindows, runtime.core.languageDirection)
    }
}
