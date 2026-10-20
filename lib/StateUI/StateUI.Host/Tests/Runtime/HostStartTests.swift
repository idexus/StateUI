// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import Synchronization
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
            realizing: HostRealization(elements: [], members: []), unrealized: [], complainingTo: Self.log,
            environment: { steps.append("environment") }, kept: { steps.append("kept") },
            windows: { steps.append("windows") }, turns: { steps.append("turns") })

        XCTAssertEqual(steps, ["environment", "kept", "windows", "turns"])
    }

    /// The tree stands in the language's direction from the start, before any window comes.
    func testAStartFollowsTheLanguagesDirection() {
        let runtime = HostRuntime.still()
        var directionAtWindows: LayoutDirection?

        runtime.start(
            realizing: HostRealization(elements: [], members: []), unrealized: [], complainingTo: Self.log,
            environment: {}, windows: { directionAtWindows = runtime.tree.languageDirection })

        XCTAssertEqual(directionAtWindows, runtime.core.languageDirection)
    }

    /// From its start a host's log hears every complaint the application routes nowhere, as a line of the host's.
    func testAStartedHostsLogHearsTheComplaints() {
        let heard = Heard()
        let runtime = HostRuntime.still()
        runtime.start(
            realizing: HostRealization(elements: [], members: []), unrealized: [],
            complainingTo: HostLog(host: "Test") { line in heard.add(line) }, environment: {})
        defer { Complaints.routeByDefault(to: nil) }

        Complaints.say("HostStartTests: said to the host")

        XCTAssertEqual(heard.lines, ["StateUI Test: HostStartTests: said to the host\n"])
    }

    /// A log that writes nowhere.
    private static let log = HostLog(host: "Test") { _ in }
}

/// What a log was handed, from any thread.
private final class Heard: Sendable {
    private let held = Mutex<[String]>([])
    var lines: [String] { held.withLock { $0 } }
    func add(_ line: String) { held.withLock { $0.append(line) } }
}
